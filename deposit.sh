# validators

KEYSOTRES='[
  {"pubkey": "b9d80028451da205ab2f8a0c8d8b72a840316e40179b02361cb8218734dca235e46e2ebb18d8e0fb7a7e804b2652da6f", "withdrawal_credentials": "010000000000000000000000b1ee8fc20d7ac4af4568aa46623a55ec31e0822a", "amount": 32000000000, "signature": "9046fe5bcbfcc49248310cbae11a29ef2c2726c7d6997c89fa05dfa6fc4c93adac9da90ed2d33fa38f1c921b1517fbf61456ecaa21f90c8ea2d604274f958cca4853ec15bf406667697d5742910effc5d57c298c127786c206fc5b59f06ca96f", "deposit_message_root": "bb2aba8dae99c1bc40d192e992d46e6af24bd8519e79503d8500d8b7316680ff", "deposit_data_root": "c225142e95dd56bbad7d8f8d65147370ade4df5bf26fe54e1018b4bc13785280", "fork_version": "00000084", "network_name": "joc", "deposit_cli_version": "1.2.2"},
  {"pubkey": "967ea97033253dc385f41da8e270a1d75a641f38eda9e05fa4d8f28783a10a6b909bb033934db90f13584b0e7a34f092", "withdrawal_credentials": "010000000000000000000000b1ee8fc20d7ac4af4568aa46623a55ec31e0822a", "amount": 32000000000, "signature": "ab4560fe02b57c6a0b6ac25d7d7adba1d91887c7220534fca3a97696dc786636c5956a0f4ae20c9fb7b508bad2464bc30878845c082e1ae8f33457dcaa10a2c6d79416517535dc703284726451153606604137a9899292ecba9ffa9979b229b6", "deposit_message_root": "760ec8b9d136418231d3101f32cfd5a033f5112cd479ce9c188a40130be67aea", "deposit_data_root": "49465478b6df0dc448456e860dc51f8a7ec87d0af4c7f8db1d4faff497b8acc7", "fork_version": "00000084", "network_name": "joc", "deposit_cli_version": "1.2.2"}
]'

PRIVATE_KEY=0x152cca97c7be44efa3a405fc53f8019403ecf780bdfc14755334493f74d5e816
RPC_URL=http://34.104.185.243:8545
DEPOSIT_CONTRACT_ADDRESS=0x4242424242424242424242424242424242424242

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
