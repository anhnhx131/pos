# validators

KEYSOTRES='[
    {
        "pubkey": "b428e5e4991b7cc27b0bb70735bdeb736bd95f01e05a2c4326b2eef9e452f478f7b24bb16c65f8d5720df911243e0523",
        "withdrawal_credentials": "01000000000000000000000004b8a24201bea7aee98406ca25b2a03bab8f435c",
        "amount": 32000000000,
        "signature": "b81b1fe9a374818f04692fd01e35d939bba5a9a9033af88ff9883489db8bdc1ca71456a988db0cb60a6768d5f48c93c00d0e39a81410d51e0c2fee8c9e04cecabe87b645ff802e7c1f872b8b1a9f2fe891ddb2f8946b8cfa5cf661e877e94856",
        "deposit_message_root": "893f2f01def1c933f4efcbc816994f0dfa0b64be0c416a18fe5c26d9cb45181b",
        "deposit_data_root": "0324c00aa66dbb00587d5c65fa886baf360b7d86955ab3c3d178c6c2ebe7ffb8",
        "fork_version": "00000051",
        "network_name": "joc",
        "deposit_cli_version": "1.2.2"
    },
     {
        "pubkey": "a259cd3bd169a182833159eab8893317eeedf2970a20d36629745caef32c7ee50a363d6ece0a578e833cc42b7d97c7f3",
        "withdrawal_credentials": "0100000000000000000000007ce5fea52a9c3b23251a8cabfbf0abab5c6e6c0d",
        "amount": 32000000000,
        "signature": "84ffacfb6dce1ce9bdccbea6d7d7205711985b07b370596e5fe8f5e2975d4b398e37492f8e5af50086af3f2242dd06a3011bc0fe95eadc39e38ae62685c26a70b67e41140e51d3f69402496137aad1b9d873031e40bb285e8b8ce8812b6a5b83",
        "deposit_message_root": "cd927ea2e1e5b9e9ee2367fd124005857f12d769c47a2f6e93fca446762aa411",
        "deposit_data_root": "0c536076ee79620f31911483cdaf040bb4e31a05c06fe0bbd622357e2d3ee009",
        "fork_version": "00000051",
        "network_name": "joc",
        "deposit_cli_version": "1.2.2"
    }
]'

PRIVATE_KEY=0x152cca97c7be44efa3a405fc53f8019403ecf780bdfc14755334493f74d5e816
RPC_URL=http://18.138.249.132:8545/
DEPOSIT_CONTRACT_ADDRESS=0xd2bee25f46ce2d92c868f3c07209675340039765

# 10049

# Map từng phần tử trong mảng thành các lệnh deposit
echo "$KEYSOTRES" | jq -c '.[]' | while read -r item; do
  PUBKEY=$(echo "$item" | jq -r '.pubkey')
  WITHDRAWAL_CREDENTIALS=$(echo "$item" | jq -r '.withdrawal_credentials')
  SIGNATURE=$(echo "$item" | jq -r '.signature')
  DEPOSIT_DATA_ROOT=$(echo "$item" | jq -r '.deposit_data_root')
  
  PRIVATE_KEY="$PRIVATE_KEY" \
  PUBKEY="0x$PUBKEY" \
  WITHDRAWAL_CREDENTIALS="0x$WITHDRAWAL_CREDENTIALS" \
  SIGNATURE="0x$SIGNATURE" \
  DEPOSIT_DATA_ROOT="0x$DEPOSIT_DATA_ROOT" \
  RPC_URL=$RPC_URL \
  DEPOSIT_CONTRACT_ADDRESS=$DEPOSIT_CONTRACT_ADDRESS \
  sh interact-eth1/cli/deposit.sh
done


# PRIVATE_KEY=0x152cca97c7be44efa3a405fc53f8019403ecf780bdfc14755334493f74d5e816 \
# PUBKEY=0xab6f42ce128888c79e290ee2711ecdffc655a9fbaeded5be286166d53963a3c36590cb4fea5318f5dae59bee236fa644 \
# WITHDRAWAL_CREDENTIALS=0x010000000000000000000000b1ee8fc20d7ac4af4568aa46623a55ec31e0822a \
# SIGNATURE=0xa24eee0c4c831454a9c7b54fbd4d8b8c237971e5aa0dcb7b92873fb24f044a0873eeaca28db8f20c2568c51eb2fd68e70feeed5f0384de0e370096686382fd85d6079d9b9dd6eb3ebcd7692917937d8abdbcc4d2d5457fb7ec91ee4f59be5130 \
# DEPOSIT_DATA_ROOT=0x3a6756904083ab7fc2e1f1af6d336610a4d50e3717bb8eb45d28151f8f5c18ec \
# sh interact-eth1/cli/deposit.sh
