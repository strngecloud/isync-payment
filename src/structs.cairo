use starknet::ContractAddress;

// Event structs have been moved to their respective files in the events/ directory:
// - accountEvents.cairo: Account-related events
// - liquidityBridgeEvents.cairo: Liquidity bridge related events
// - accountFactoryEvents.cairo: Account factory related events

// Remaining structs below

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct PaymentRecord {
    pub from: ContractAddress,
    pub to: ContractAddress,
    /// The currency used for the payment (e.g., 'USD', 'EUR')
    pub currency: felt252,
    pub amount: u128,
    pub timestamp: u64,
    pub used_bridge: bool,
}
// impl PaymentRecord {
//     /// Creates a new PaymentRecord
//     pub fn new(
//         from: ContractAddress,
//         to: ContractAddress,
//         currency: felt252,
//         amount: u128,
//         timestamp: u64,
//         used_bridge: bool,
//     ) -> Self {
//         Self {
//             from,
//             to,
//             currency,
//             amount,
//             timestamp,
//             used_bridge,
//         }
//     }

//     /// Checks if the payment record is valid (non-zero addresses and amount)
//     pub fn is_valid(self: @PaymentRecord) -> bool {
//         !(*self.from).is_zero()
//             && !(*self.to).is_zero()
//             && *self.amount > 0
//             && *self.currency != 0
//     }

//     /// Returns true if this payment used the liquidity bridge
//     pub fn used_liquidity_bridge(self: @PaymentRecord) -> bool {
//         *self.used_bridge
//     }

//     /// Gets the payment amount
//     pub fn get_amount(self: @PaymentRecord) -> u128 {
//         *self.amount
//     }

//     /// Gets the payment currency
//     pub fn get_currency(self: @PaymentRecord) -> felt252 {
//         *self.currency
//     }

//     /// Gets the sender address
//     pub fn get_sender(self: @PaymentRecord) -> ContractAddress {
//         *self.from
//     }

//     /// Gets the recipient address
//     pub fn get_recipient(self: @PaymentRecord) -> ContractAddress {
//         *self.to
//     }

//     /// Gets the payment timestamp
//     pub fn get_timestamp(self: @PaymentRecord) -> u64 {
//         *self.timestamp
//     }
// }

// /// Default implementation for PaymentRecord
// impl Default<PaymentRecord> of Default<PaymentRecord> {
//     fn default() -> PaymentRecord {
//         PaymentRecord {
//             from: starknet::contract_address_const::<0>(),
//             to: starknet::contract_address_const::<0>(),
//             currency: 0,
//             amount: 0,
//             timestamp: 0,
//             used_bridge: false,
//         }
//     }
// }

// /// Trait for converting PaymentRecord to and from storage format
// trait PaymentRecordStorageTrait {
//     fn to_storage(self: PaymentRecord) -> (felt252, felt252, felt252, felt252, felt252, felt252);
//     fn from_storage(data: (felt252, felt252, felt252, felt252, felt252, felt252)) ->
//     PaymentRecord;
// }

// impl PaymentRecordStorageImpl of PaymentRecordStorageTrait {
//     fn to_storage(self: PaymentRecord) -> (felt252, felt252, felt252, felt252, felt252, felt252)
//     {
//         (
//             self.from.into(),
//             self.to.into(),
//             self.currency,
//             self.amount.into(),
//             self.timestamp.into(),
//             if self.used_bridge { 1 } else { 0 }
//         )
//     }

//     fn from_storage(data: (felt252, felt252, felt252, felt252, felt252, felt252)) ->
//     PaymentRecord {
//         let (from, to, currency, amount, timestamp, used_bridge) = data;
//         PaymentRecord {
//             from: from.try_into().unwrap(),
//             to: to.try_into().unwrap(),
//             currency,
//             amount: amount.try_into().unwrap(),
//             timestamp: timestamp.try_into().unwrap(),
//             used_bridge: used_bridge == 1,
//         }
//     }
// }


