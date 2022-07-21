import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { Deployment } from "hardhat-deploy/dist/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments } = hre
  const { all } = deployments
/*
  const allContracts: { [p: string]: Deployment } = await all()
  console.table(
    Object.keys(allContracts).map((k) => [k, allContracts[k].address]),
  )
*/
}
export default func
func.tags = ["PrintAddresses"]
func.runAtTheEnd = true
