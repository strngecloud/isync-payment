#[starknet::interface]
trait IPragmaMock<TContractState> {
    fn get_data_median(
        self: @TContractState, data_type: pragma_lib::types::DataType,
    ) -> pragma_lib::types::PragmaPricesResponse;
}

#[starknet::contract]
mod PragmaMock {
    use pragma_lib::types::{DataType, PragmaPricesResponse};
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        price: u128,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.price.write(2000 * 10_u128.pow(8)); // Default price $2000 with 8 decimals
    }

    #[external(v0)]
    impl PragmaMockImpl of super::IPragmaMock<ContractState> {
        fn get_data_median(self: @ContractState, data_type: DataType) -> PragmaPricesResponse {
            PragmaPricesResponse {
                price: self.price.read(),
                decimals: 8,
                last_updated_timestamp: 12345,
                num_sources_aggregated: 10,
                expiration_timestamp: 0,
            }
        }
    }
}
