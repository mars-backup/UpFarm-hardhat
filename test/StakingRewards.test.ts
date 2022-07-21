import { Signer } from "ethers"
import { deployments } from "hardhat"
import { solidity } from "ethereum-waffle"
import chai from "chai"
import { mineBlocks } from "./testUtils"
import {
  Core,
  StakingRewards,
  UpToken
} from '../build/typechain'

chai.use(solidity)
const { expect } = chai
const { get } = deployments

const one = '1000000000000000000'

describe("StakingRewards unit test", () => {
  let core: Core
  let stakingRewards: StakingRewards
  let up: UpToken

  let owner: Signer
  let dev: Signer
  let attacker: Signer

  let ownerAddress: string
  let devAddress: string

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture()

      const signers = await ethers.getSigners();
      [ owner, dev, attacker ] = signers

      ownerAddress = await owner.getAddress()
      devAddress = await dev.getAddress()

      core = (await ethers.getContractAt(
        'Core',
        (
          await get("Core")
        ).address
      )) as Core

      stakingRewards = (await ethers.getContractAt(
        'StakingRewards',
        (
          await get("StakingRewardsCAKE")
        ).address
      )) as StakingRewards

      up = (await ethers.getContractAt(
        'UpToken',
        (
          await get('UP')
        ).address
      )) as UpToken

      await stakingRewards.setPool(0, 100, true)
    }
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe('poolLength', () => {
    it('success', async () => {
      expect(await stakingRewards.poolLength()).to.equal(1)
    })
  })

  describe('addPool', () => {
    it('onlyGuardianOrGovernor', async () => {
      const xmsAddress = (await get('XMS')).address
      await expect(stakingRewards.connect(attacker).addPool(10, xmsAddress, true)).to.be.revertedWith("CoreRef::onlyGuardianOrGovernor: Caller is not a guardian or governor")
    })

    it('nonDuplicated', async () => {
      await expect(stakingRewards.addPool(10, up.address, true)).to.be.revertedWith("StakingReward::nonDuplicated: Duplicated")
    })

    it('success', async () => {
      const xmsAddress = (await get('XMS')).address
      await stakingRewards.addPool(100, xmsAddress, true)
      expect(await stakingRewards.poolLength()).to.equal(2)
    })
  })

  describe('setPool', () => {
    it('onlyGuardianOrGovernor', async () => {
      await expect(stakingRewards.connect(attacker).setPool(0, 10, true)).to.be.revertedWith("CoreRef::onlyGuardianOrGovernor: Caller is not a guardian or governor")
    })

    it('validatePid', async () => {
      await expect(stakingRewards.setPool(10, 100, true)).to.be.revertedWith("StakingReward::validatePid: Not exist")
    })

    it('success', async () => {
     await stakingRewards.setPool(0, 100, true)
     const p = await stakingRewards.poolInfo(0)
     expect(p.allocPoint).to.equal(100)
    })
  })

  describe("deposit", () => {
    beforeEach(async () => {
      await up.transfer(devAddress, one)
    })

    it("should not be able to deposit when paused", async () => {
      await stakingRewards.pause()
      await up.connect(dev).approve(stakingRewards.address, one)
      await expect(stakingRewards.connect(dev).deposit(0, one))
        .to.be.revertedWith("Pausable: paused")
    })

    it("should be able to deposit successfully", async () => {
      await up.connect(dev).approve(stakingRewards.address, one)
      await stakingRewards.connect(dev).deposit(0, one)
      const u =await stakingRewards.userInfo(0, devAddress)
      expect(u.amount).to.equal(one)
    })
  })

  describe('pendingReward', () => {
    const amount = '1000000'
    it('success', async () => {
      await up.approve(stakingRewards.address, amount)
      await stakingRewards.deposit(0, amount)

      await mineBlocks(10)

      expect(await stakingRewards.pendingToken(0, ownerAddress)).to.equal('5000000000000000000')
    })
  })

  describe('withdraw', () => {
    const amount = '1000000'
    it('success', async () => {
      const old = await up.balanceOf(ownerAddress)
      await up.approve(stakingRewards.address, amount)
      await stakingRewards.deposit(0, amount)
      await stakingRewards.withdraw(0, amount)
      expect(await up.balanceOf(ownerAddress)).to.equal(old)
      const u = await stakingRewards.userInfo(0, ownerAddress)
      expect(u.amount).to.equal(0)
    })
  })

  describe('emergencyWithdraw', () => {
    const amount = '1000000'
    it('success', async () => {
      await up.approve(stakingRewards.address, amount)
      await stakingRewards.deposit(0, amount)
      await stakingRewards.emergencyWithdraw(0)
      expect(await stakingRewards.balanceOf(ownerAddress)).to.equal(0)
      const u = await stakingRewards.userInfo(0, ownerAddress);
      expect(u.amount).to.equal(0)
      expect(u.rewardDebt).to.equal(0)
    })
  })

  describe('updateUpPerBlock', () => {
    it('onlyGuardianOrGovernor', async () => {
      await expect(stakingRewards.connect(attacker).updateTokenPerBlock(0))
        .to.be.revertedWith("CoreRef::onlyGuardianOrGovernor: Caller is not a guardian or governor")
    })

    it('success', async () => {
      await expect(stakingRewards.updateTokenPerBlock(0))
        .to.emit(stakingRewards, 'UpdateEmissionRate')
        .withArgs(ownerAddress, 0)
    })
  })
})