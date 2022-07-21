import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { keccak256 } from "@ethersproject/keccak256"

const MASTER_ROLE = keccak256(Buffer.from('MASTER_ROLE', 'utf-8'))

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { execute, getOrNull, save, get } = deployments
  const { deployer } = await getNamedAccounts()

  const name = "UpFarmGrant"
  const grant = await getOrNull(name)
  if (grant) return

  await execute(
    "Core",
    { from: deployer, log: true },
    "grantRole",
    MASTER_ROLE,
    (await get("UpFarm")).address
  )

  await save(name , {
    abi: (await get("UpFarm")).abi,
    address: (await get("UpFarm")).address
  })
}

export default func
func.tags = ["UpFarmGrant"]
func.dependencies = ["Core","UpFarm"]