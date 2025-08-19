# Declare Account
sncast declare --contract-name Account --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --package isyncpayment

## command: declare
class_hash: 0x022e5652c95ab64784909deae322d41f81d8fb89d8590ccb22add66bfe21fe8b
transaction_hash: 0x04590521bdc004e2dd4991afcd2ae426f7cd39f3858359ae9f6fb44c01f7133f

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
class_hash: 0x013d4aa8cfbeea7616a93e2da6c196137f34056b2c076a674ce603f1f1c53b9b
transaction_hash: 0x06dff93d8f9eb05616f7ef70ac0bf97310029962cf2f2620ffef517006a659a9

# Deploy Liquidity Bridge
sncast deploy --class-hash 0x018b7ac0774b31e04fbc50ce952869db5d3f286f458e6791f290dc82427df916 --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --constructor-calldata 0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 1000

## command: deploy
contract_address: 0x05f4fcb2921ba790a2d3cffa6c040a9446ab17e4549258e329b8c40bae8945b9
transaction_hash: 0x01c4d3d272d5ed33338d1d2e388e04e0361061fab892442765ce5c9da245b4e7

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
