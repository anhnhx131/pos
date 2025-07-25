import { createWalletClient, http, parseAbi, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";

async function main() {
  if (
    !process.env.PRIVATE_KEY ||
    !process.env.PUBKEY ||
    !process.env.WITHDRAWAL_CREDENTIALS ||
    !process.env.SIGNATURE ||
    !process.env.DEPOSIT_DATA_ROOT
  ) {
    throw new Error("Missing environment variables");
  }

  const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`);

  const walletClient = createWalletClient({
    account,
    transport: http("http://localhost:8545"),
  });

  await walletClient.writeContract({
    address: "0x4242424242424242424242424242424242424242",
    abi: parseAbi([
      "function deposit(bytes calldata pubkey, bytes calldata withdrawal_credentials, bytes calldata signature, bytes32 deposit_data_root) external",
    ]),
    functionName: "deposit",
    args: [
      process.env.PUBKEY as `0x${string}`,
      process.env.WITHDRAWAL_CREDENTIALS as `0x${string}`,
      process.env.SIGNATURE as `0x${string}`,
      process.env.DEPOSIT_DATA_ROOT as `0x${string}`,
    ],
    value: parseEther("32"),
  } as any);
}

main();
