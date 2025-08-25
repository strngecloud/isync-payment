#[starknet::interface]
pub trait IPragma<T> {
    fn get_asset_price(self: @T, asset_id: felt252) -> u128;
}

