import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { isMainnet } from "../utils/network"
import BigNumber from "bignumber.js"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre
  const { deploy, execute, getOrNull, log } = deployments
  const { deployer } = await getNamedAccounts()

  if (isMainnet(await getChainId())) return

  const token = await getOrNull("CAKE")
  if (token) {
    log(`reusing "CAKE" at ${token.address}`)
  } else {
    const result = await deploy("CAKE", {
      from: deployer,
      contract: "CakeToken",
      log: true,
      skipIfAlreadyDeployed: true
    })

    if (result.newlyDeployed) {
      await execute(
        "CAKE",
        { from: deployer, log: true },
        "mint",
        deployer,
        new BigNumber(1e24).toString(10)
      )
    }
  }
}
export default func
func.tags = ["CAKE"]