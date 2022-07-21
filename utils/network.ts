export const CHAIN_ID = {
  MAINNET: "56",
  TESTNET: "97",
  HARDHAT: "31337",
}

export function isMainnet(networkId: string): boolean {
  return networkId == CHAIN_ID.MAINNET
}

export function isTestNetwork(networkId: string): boolean {
  return [
    CHAIN_ID.HARDHAT,
    CHAIN_ID.TESTNET
  ].includes(networkId)
}