import _ from "lodash"
import { Signer } from "ethers"
import { solidity } from "ethereum-waffle"
import { ethers, deployments } from "hardhat"
import { keccak256 } from "@ethersproject/keccak256"
import chai from "chai"
import {
  VestingMaster,
  UpToken,
  Core
} from "../build/typechain"
import { increaseTimestamp } from "./testUtils"

chai.use(solidity)
const { expect } = chai
const { get } = deployments

const MASTER_ROLE = keccak256(Buffer.from('MASTER_ROLE', 'utf-8'))

describe('VestingMaster unit test',() => {

  let vesting: VestingMaster
  let up: UpToken
  let owner: Signer
  let alice: Signer
  let attacker: Signer
  let ownerAddress: string
  let aliceAddress: string

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture()
    
      const signers = await ethers.getSigners();
      [ owner, alice, attacker ] = signers
    
      ownerAddress = await owner.getAddress()
      aliceAddress = await alice.getAddress()

      vesting = (await ethers.getContractAt(
        "VestingMaster",
        (
          await get("VestingMaster")
        ).address,
      )) as VestingMaster

      up = (await ethers.getContractAt(
        "UpToken",
        (
          await get("UP")
        ).address,
      )) as UpToken

      const core = (await ethers.getContractAt(
        "Core",
        (
          await get("Core")
        ).address,
      )) as Core

      await up.transfer(vesting.address, "1000000000000000000")
      await core.grantRole(MASTER_ROLE, ownerAddress)
    }
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe( 'lock', () => {
    const amount = "1000000"
    it('onlyMaster', async () => {
      await expect(vesting.connect(attacker).lock(aliceAddress, amount))
        .to.be.revertedWith("CoreRef::onlyMaster: Caller is not a master")
    })

    it('success', async () => {
      await expect(vesting.lock(aliceAddress, amount))
        .to.emit(vesting, 'Lock')
        .withArgs(aliceAddress, amount)
    })
  })

  describe('base info', () => {
    it('base info of vesting', async () => {
      expect(await vesting.period()).to.equal(259200)
      expect(await vesting.lockedPeriodAmount()).to.equal(19)
      expect(await vesting.vestingToken()).to.equal(up.address)
    })
  })

  describe( 'claim', () => {
    const amount = "190000"
    it('claim 0 peroid success', async () => {
      await vesting.lock(aliceAddress, amount)
      const ret = await vesting.connect(alice).getVestingAmount()
      expect(ret[0]).to.equal(amount)
      expect(ret[1]).to.equal(0)
      await vesting.connect(alice).claim()
      expect(await up.balanceOf(aliceAddress)).to.equal(0)
    })

    it('claim 1 peroid success', async () => {
      await vesting.lock(aliceAddress, amount)
      await increaseTimestamp(259200)
      const ret = await vesting.connect(alice).getVestingAmount()
      expect(ret[0]).to.equal(180000)
      expect(ret[1]).to.equal(10000)
      await vesting.connect(alice).claim()
      expect(await up.balanceOf(aliceAddress)).to.equal(10000)
    })

    it('claim 2 peroid success', async () => {
      await vesting.lock(aliceAddress, amount)
      await increaseTimestamp(259200 * 2)
      const ret = await vesting.connect(alice).getVestingAmount()
      expect(ret[0]).to.equal(170000)
      expect(ret[1]).to.equal(20000)
      await vesting.connect(alice).claim()
      expect(await up.balanceOf(aliceAddress)).to.equal(20000)
    })
  })
})