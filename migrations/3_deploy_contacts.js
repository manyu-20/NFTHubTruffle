const myContract = artifacts.require("NFTContractUpdated");
module.exports = function(deployer) {
	   deployer.deploy(myContract);
};
