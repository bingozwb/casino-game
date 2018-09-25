const TestUtil = artifacts.require('TestUtil.sol')

module.exports = function(deployer) {
  deployer.deploy(TestUtil)
}
