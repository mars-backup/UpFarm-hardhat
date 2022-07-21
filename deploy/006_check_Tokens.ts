import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"
import BigNumber from "bignumber.js"

const TOKENS: { [token: string]: any[] } = {
  BUSD: ["Binance USD", "BUSD", "18"],
  XMS: ["XMS", "XMS", "18"],
  BTCB: ["BTCB", "BTCB", "18"],
  ETH: ["ETH", "ETH", "18"],
  USDm: ["USDm", "USDm", "18"],
  USDT: ["USDT", "USDT", "18"]
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute } = deployments
  const { deployer } = await getNamedAccounts()
  const mainnet = isMainnet(await getChainId())

  if (mainnet) return

  for (const token in TOKENS) {
    const result = await deploy(token, {
      from: deployer,
      log: true,
      contract: "GenericERC20",
      args: TOKENS[token],
      skipIfAlreadyDeployed: true,
    })

    if (result.newlyDeployed) {
      const decimals = TOKENS[token][2]
      await execute(
        token,
        { from: deployer, log: true },
        "mint",
        deployer,
        new BigNumber(10).pow(decimals).times(1000000).toString(10),
      )
    }
  }
}

export default func
func.tags = ["Tokens"]