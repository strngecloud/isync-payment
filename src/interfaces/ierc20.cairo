use starknet::ContractAddress;
// Dispatcher implementation
#[starknet::interface]
pub trait SyncToken<T> {
    fn get_name(self: @T) -> felt252;
    fn get_symbol(self: @T) -> felt252;
    fn get_decimals(self: @T) -> u8;
    fn total_supply(self: @T) -> u256;
    fn balance_of(self: @T, account: ContractAddress) -> u256;
    fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(self: @T, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        self: @T, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(self: @T, spender: ContractAddress, amount: u256) -> bool;
    fn increase_allowance(
        self: @T, spender: ContractAddress, added_value: u256,
    ) -> bool;
    fn decrease_allowance(
        self: @T, spender: ContractAddress, subtracted_value: u256,
    ) -> bool;
    fn mint(self: @T, recipient: ContractAddress, amount: u256);
    fn burn(self: @T, value: u256);
}
//     #[starknet::embeddable]
//     impl IsyncpaymentImpl of IIsyncpaymentDispatcher<ContractState> {
//         fn get_name(self: @ContractState) -> felt252 {
//             self.erc20.name()
//         }

//         fn get_symbol(self: @ContractState) -> felt252 {
//             self.erc20.symbol()
//         }

//         fn get_decimals(self: @ContractState) -> u8 {
//             self.erc20.decimals()
//         }

//         fn total_supply(self: @ContractState) -> u256 {
//             self.erc20.total_supply()
//         }

//         fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
//             self.erc20.balance_of(account)
//         }

//         fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) ->
//         u256 {
//             self.erc20.allowance(owner, spender)
//         }

//         fn transfer(self: @ContractState, recipient: ContractAddress, amount: u256) -> bool {
//             self.erc20.transfer(recipient, amount)
//         }

//         fn transfer_from(
//             self: @ContractState, sender: ContractAddress, recipient: ContractAddress, amount:
//             u256
//         ) -> bool {
//             self.erc20.transfer_from(sender, recipient, amount)
//         }

//         fn approve(self: @ContractState, spender: ContractAddress, amount: u256) -> bool {
//             self.erc20.approve(spender, amount)
//         }

//         fn increase_allowance(self: @ContractState, spender: ContractAddress, added_value: u256)
//         -> bool {
//             self.erc20.increase_allowance(spender, added_value)
//         }

//         fn decrease_allowance(self: @ContractState, spender: ContractAddress, subtracted_value:
//         u256) -> bool {
//             self.erc20.decrease_allowance(spender, subtracted_value)
//         }

//         fn mint(self: @ContractState, recipient: ContractAddress, amount: u256) {
//             self.mint(recipient, amount)
//         }

//         fn burn(self: @ContractState, value: u256) {
//             self.burn(value)
//         }
//     }

//     // Expose the dispatcher
//     #[starknet::interface]
//     pub trait IIsyncpaymentDispatcherTrait<T> {
//         fn get_name(self: @T) -> felt252;
//         fn get_symbol(self: @T) -> felt252;
//         fn get_decimals(self: @T) -> u8;
//         fn total_supply(self: @T) -> u256;
//         fn balance_of(self: @T, account: ContractAddress) -> u256;
//         fn allowance(self: @T, owner: ContractAddress, spender: ContractAddress) -> u256;
//         fn transfer(self: @T, recipient: ContractAddress, amount: u256) -> bool;
//         fn transfer_from(self: @T, sender: ContractAddress, recipient: ContractAddress, amount:
//         u256) -> bool;
//         fn approve(self: @T, spender: ContractAddress, amount: u256) -> bool;
//         fn increase_allowance(self: @T, spender: ContractAddress, added_value: u256) -> bool;
//         fn decrease_allowance(self: @T, spender: ContractAddress, subtracted_value: u256) ->
//         bool;
//         fn mint(self: @T, recipient: ContractAddress, amount: u256);
//         fn burn(self: @T, value: u256);
//     }

//     #[starknet::embeddable]
//     impl IsyncpaymentDispatcherImpl of IIsyncpaymentDispatcherTrait<ContractState> {
//         fn get_name(self: @ContractState) -> felt252 {
//             self.erc20.name()
//         }

//         fn get_symbol(self: @ContractState) -> felt252 {
//             self.erc20.symbol()
//         }

//         fn get_decimals(self: @ContractState) -> u8 {
//             self.erc20.decimals()
//         }

//         fn total_supply(self: @ContractState) -> u256 {
//             self.erc20.total_supply()
//         }

//         fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
//             self.erc20.balance_of(account)
//         }

//         fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) ->
//         u256 {
//             self.erc20.allowance(owner, spender)
//         }

//         fn transfer(self: @ContractState, recipient: ContractAddress, amount: u256) -> bool {
//             self.erc20.transfer(recipient, amount)
//         }

//         fn transfer_from(
//             self: @ContractState, sender: ContractAddress, recipient: ContractAddress, amount:
//             u256
//         ) -> bool {
//             self.erc20.transfer_from(sender, recipient, amount)
//         }

//         fn approve(self: @ContractState, spender: ContractAddress, amount: u256) -> bool {
//             self.erc20.approve(spender, amount)
//         }

//         fn increase_allowance(self: @ContractState, spender: ContractAddress, added_value: u256)
//         -> bool {
//             self.erc20.increase_allowance(spender, added_value)
//         }

//         fn decrease_allowance(self: @ContractState, spender: ContractAddress, subtracted_value:
//         u256) -> bool {
//             self.erc20.decrease_allowance(spender, subtracted_value)
//         }

//         fn mint(self: @ContractState, recipient: ContractAddress, amount: u256) {
//             self.mint(recipient, amount)
//         }

//         fn burn(self: @ContractState, value: u256) {
//             self.burn(value)
//         }
//     }
// }

