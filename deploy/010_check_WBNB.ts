import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"
import BigNumber from "bignumber.js"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()
  const mainnet = isMainnet(await getChainId())

  if (mainnet) return

  const wbnb = await getOrNull("WBNB")
  if (wbnb) {
    log(`reusing "WBNB" at ${wbnb.address}`)
  } else {
    const result = await deploy("WBNB", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true
    })

    if (result.newlyDeployed) {
      await execute(
        "WBNB",
        { from: deployer, log: true, value: new BigNumber(1e19).times(6).toString(10) },
        "deposit"
      )
    }
  }
}
export default func
func.tags = ["WBNB"]