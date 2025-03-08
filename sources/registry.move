module dos_registry::registry;

use std::type_name::{Self, TypeName};
use sui::event::emit;
use sui::table::{Self, Table};

public use fun registry_admin_cap_registry_id as RegistryAdminCap.registry_id;

public struct Registry<phantom T: key, phantom K: copy + drop + store> has key, store {
    id: UID,
    kind: RegistryKind,
    obj_ids: Table<K, ID>,
}

public struct RegistryAdminCap<phantom T: key> has key, store {
    id: UID,
    registry_id: ID,
}

public enum RegistryKind has copy, drop, store {
    CAPPED { max_size: u64 },
    UNCAPPED,
}

public struct RegistryCreatedEvent has copy, drop {
    registry_id: ID,
    registry_item_type: TypeName,
}

public struct ObjectIdAddedEvent<K: copy + drop + store> has copy, drop {
    registry_id: ID,
    obj_key: K,
    obj_id: ID,
}

public struct ObjectIdRemovedEvent<K: copy + drop + store> has copy, drop {
    registry_id: ID,
    obj_key: K,
    obj_id: ID,
}

const ERegistryMaxSizeReached: u64 = 0;
const EInvalidRegistryAdminCap: u64 = 1;

public fun new<T: key, K: copy + drop + store>(
    kind: RegistryKind,
    ctx: &mut TxContext,
): (Registry<T, K>, RegistryAdminCap<T>) {
    let registry = Registry {
        id: object::new(ctx),
        kind: kind,
        obj_ids: table::new(ctx),
    };

    let registry_admin_cap = RegistryAdminCap {
        id: object::new(ctx),
        registry_id: registry.id.to_inner(),
    };

    emit(RegistryCreatedEvent {
        registry_id: registry.id.to_inner(),
        registry_item_type: type_name::get<T>(),
    });

    (registry, registry_admin_cap)
}

public fun new_capped_kind(max_size: u64): RegistryKind {
    RegistryKind::CAPPED { max_size }
}

public fun new_uncapped_kind(): RegistryKind {
    RegistryKind::UNCAPPED
}

public fun add<T: key, K: copy + drop + store>(
    self: &mut Registry<T, K>,
    cap: &RegistryAdminCap<T>,
    key: K,
    obj: &T,
) {
    assert!(cap.registry_id == self.id.to_inner(), EInvalidRegistryAdminCap);

    match (self.kind) {
        RegistryKind::CAPPED { max_size } => {
            assert!(self.size() < max_size, ERegistryMaxSizeReached);
        },
        RegistryKind::UNCAPPED => {},
    };

    self.obj_ids.add(key, object::id(obj));

    emit(ObjectIdAddedEvent<K> {
        registry_id: self.id.to_inner(),
        obj_key: key,
        obj_id: object::id(obj),
    });
}

public fun remove<T: key, K: copy + drop + store>(
    self: &mut Registry<T, K>,
    cap: &RegistryAdminCap<T>,
    key: K,
) {
    assert!(cap.registry_id == self.id.to_inner(), EInvalidRegistryAdminCap);

    let obj_id = self.obj_ids.remove(key);

    emit(ObjectIdRemovedEvent<K> {
        registry_id: self.id.to_inner(),
        obj_key: key,
        obj_id: obj_id,
    });
}

public fun obj_id_from_key<T: key, K: copy + drop + store>(self: &Registry<T, K>, key: K): ID {
    *self.obj_ids.borrow(key)
}

public fun size<T: key, K: copy + drop + store>(self: &Registry<T, K>): u64 {
    self.obj_ids.length()
}

public fun registry_admin_cap_registry_id<T: key>(cap: &RegistryAdminCap<T>): ID {
    cap.registry_id
}
