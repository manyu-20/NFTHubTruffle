// contracts/MyContract.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// pragma solidity ^0.8.20;

contract MyContract {
    uint256 public myNumber;

    function getNumber() public view returns (uint256) {
        return myNumber;
    }

    function updateNumber(uint256 _newNumber) public {
        myNumber = _newNumber;
    }
}
