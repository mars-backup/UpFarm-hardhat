import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { deploy, execute, getOrNull, log, get } = deployments
  const { deployer } = await getNamedAccounts()

  const timelock = await getOrNull("TimelockController")
  if (timelock) {
    log(`reusing "TimelockController" at ${timelock.address}`)
  } else {
    const result = await deploy("TimelockController", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        60,
        30,
        [
          deployer,
          "0x3360deC490E74605c65CDb8D2F87137c1C5E8345"
        ],
        [
          deployer,
          "0xfE08B6D4c02179734723cBa7BDc487eF8d8a7c22"
        ]
      ]
    })

    if (result.newlyDeployed) {
      await execute(
        "Core",
        { from: deployer, log: true },
        "grantGovernor",
        (await get("TimelockController")).address
      )
    }
  }
}

export default func
func.tags = ["TimelockController"]
func.dependencies = ["Core"]