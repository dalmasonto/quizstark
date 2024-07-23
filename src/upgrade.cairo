use starknet::class_hash::ClassHash;

#[starknet::interface]
pub trait IUpgradeableContract<TContractState> {
    fn upgrade(ref self: TContractState, impl_hash: ClassHash);
}