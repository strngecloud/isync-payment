# Declare Account
sncast declare --contract-name Account --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --package isyncpayment

## command: declare
class_hash: 0x055d6258fdf145e784eb9b267e86d5a944c55ed3f24a5b872ecb4dd9ed7ba1bf
transaction_hash: 0x01802f0379a4f92975c00f316479d0ddc64c92ab2031cf4cd1aa697799dbf4c9

# Declare Account Factory
sncast declare --contract-name AccountFactory --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --package isyncpayment

## command: declare
class_hash: 0x033168d3b6bb2042404612bb154e8f01f6a326af58621a7be17a098f9730a85c
transaction_hash: 0x02be37cb322632ded496353db82aaeb85859cdbcf61279066491c701fd3db46e

# Deploy Account Factory
sncast deploy --class-hash 0x05222ad7940648766984a322d738f81131dffe71e76822473d59e91f7f616467 --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --constructor-calldata 0x00af7426c058322f65f99d991c023a0abbc082d0d67796f1999cea5f396dac71 0x0715b9c5434bdb216bca48c2162ec745def13bfc35df70b1be688d05c14ad4b0 0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27

## command: deploy
contract_address: 0x04e6a49ed6a43811b443778f129d632a752c633f6e1535c2fd15aa887263e8a9
transaction_hash: 0x03af37f91ac05bb57b4b838add955191acfa0aec7d72a38ac5799d5bdd81af65

# Declare Liquidity Bridge
sncast declare --contract-name LiquidityBridge --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --package isyncpayment

## command: declare
class_hash: 0x0640618820a7f3d33d0c74980ede947947837d608c69f7ad6e7b931d009d68f3
transaction_hash: 0x07c0fd1ccb40f1907443c1f338ce40b7114d1f9d491fc7a8014a5329f3cd7e18

# Deploy Liquidity Bridge
sncast deploy \
  --class-hash 0x0640618820a7f3d33d0c74980ede947947837d608c69f7ad6e7b931d009d68f3 \
  --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n \
  --constructor-calldata \
    0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \
    0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \
    1000 \
    0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b \
    2 \
    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 \
    0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d \
    2 \
    0x4554482f555344 \
    0x5354524b2f555344

## command: deploy
contract_address: 0x0078da3daf76a5cd44ba7a55629f02f11ef419eaa1773ce390f1de1e627da447
transaction_hash: 0x0552af49c45d896673c72b2c3e7787cf8b3b142607f091ff150d53d25d90faf2

# Declare Sync Token
sncast declare --contract-name SyncToken --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --package isyncpayment

## command: declare
class_hash: 0x029ec83455b6774b26be742f1a2efd12132a4a4fb51d2a39a0aff55334e1f7d0
transaction_hash: 0x00a22ed4f27e86ff0c0edc21af7c2ef5e9a65aac8aae71a895967de5385bbbb8

# Deploy Sync Token
sncast deploy --class-hash 0x029ec83455b6774b26be742f1a2efd12132a4a4fb51d2a39a0aff55334e1f7d0 --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --constructor-calldata 0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27

## command: deploy
contract_address: 0x06ab048153cdf6ee3ab9328fa0b8d16c09670581a5a446749facfd229362bf0e
transaction_hash: 0x074dbdda17b04b2b04781966758ed1dff60f738e214b27721ed388ac3dd6c6de
