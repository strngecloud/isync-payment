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

command: declare
class_hash: 0x04d0116e741631dacd290ad6e948b80bc2effd0e3bf18f1b0ee0eac427fbb61b
transaction_hash: 0x00dfeb16f045e53e68dc59dcb8bff222ac38d2b0749eae1dd4155b4e549f7f0d

command: declare
class_hash: 0x00a124fe416e557dda1f767c48fd7f8e9a91f53a691e2684dccaf588a3472ca9
transaction_hash: 0x059c4bf98da5bca67582aefd48816b0785c83490314a5128f4674cdd57d5d5fc

# Deploy Liquidity Bridge
sncast deploy \
  --class-hash 0x04d0116e741631dacd290ad6e948b80bc2effd0e3bf18f1b0ee0eac427fbb61b \
  --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n \
  --constructor-calldata \
    0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \
    0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 \
    1000 \
    0x36031daa264c24520b11d93af622c848b2499b66b41d611bac95e13cfca131a \
    2 \
    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 \
    0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d \
    2 \
    0x4554482f555344 \
    0x5354524b2f555344

command: deploy
contract_address: 0x079d34f36f135f787af3a0fc2556613b22f1bd4da15378ccf71b5dbb1cae5022
transaction_hash: 0x003c5ff422e9c63e56eb973bb4a7bfa94c1fb05e940e4246818cbbb25f18f702




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




# Declare Sync Staker
sncast declare --contract-name SyncStaking --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --package isyncpayment

## command: declare
class_hash: 0x02006bcf684c595efb1d05fa8266a309b8ba97e65f60afb989e104528bec0e91
transaction_hash: 0x049231fa4afdcf7e278352a32eb012cd083f5b1c47e5f6654d72cd860c249773

# Deploy Sync Token
sncast deploy --class-hash 0x02b6b1c7c27fe84e418e658d48eeef87aee2f76640e11a56c37f8082009131c8 --url https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/VFVA--IYkSjn28CaMokBNYvFo5fZOw2n --constructor-calldata 0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 0x079d34f36f135f787af3a0fc2556613b22f1bd4da15378ccf71b5dbb1cae5022 0x04e6a49ed6a43811b443778f129d632a752c633f6e1535c2fd15aa887263e8a9 0x4c73687f23639fdfd8d7d71ea7fccd62866351b0eff5efea14148c7b6ee5b27 1000

## command: deploy
contract_address: 0x038d3c8ce3b47e39b48458427048634f1207bab0275cb969cbc3363f8b2a922b
transaction_hash: 0x02ce9dbc0736a9de844a2204c325d1cbee341d5058511ade6fad0b67e045f748
