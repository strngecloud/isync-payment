pub mod accountFactory {
    pub mod accountFactory;
}

pub mod account {
    pub mod account;
}

pub mod liquidityBridge {
    pub mod liquidityBridge;
}

pub mod staking {
    pub mod staking;
}

pub mod errors;

pub mod erc20 {
    pub mod erc20;
    pub mod sNGN;
}

pub mod events {
    pub mod accountEvents;
    pub mod accountFactoryEvents;
    pub mod liquidityBridgeEvents;
    pub mod stakingEvents;
}

pub mod interfaces {
    pub mod iaccount;
    pub mod iaccountFactory;
    pub mod ierc20;
    pub mod iliquidityBridge;
    pub mod istaking;
}
