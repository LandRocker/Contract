// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}

contract Vesting is Ownable {
    // address of IERC20Mintable
    address public immutable tokenAddress;
    // vesting period in seconds
    uint256 public immutable vestingPeriod;

    struct VestingSchedule {
        bool active;
        // beneficiary of tokens after they are released
        uint256 start;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        // amount of tokens released
        uint256 released;
    }

    // stroing information about vestings
    mapping(address => VestingSchedule[]) public vestings;

    constructor(address tokenAddress_, uint256 vestingPeriod_) {
        vestingPeriod = vestingPeriod_;
        tokenAddress = tokenAddress_;
    }

    // vreate vest
    function vest(address to, uint256 amount) public onlyOwner {
        VestingSchedule memory newVestingSchedule = VestingSchedule(
            true,
            block.timestamp,
            amount,
            0
        );
        vestings[to].push(newVestingSchedule);
        IERC20Mintable(tokenAddress).mint(address(this), amount);
    }

    // updates the vestingSchedule and return amount of token to be released
    function _claim(VestingSchedule storage vestingSchedule)
        private
        returns (uint256 amountToRelease)
    {
        uint256 time = block.timestamp + 1;
        uint256 amountTotal = vestingSchedule.amountTotal;
        amountToRelease =
            (amountTotal * (time - vestingSchedule.start)) /
            vestingPeriod;
        if (amountToRelease > amountTotal) {
            amountToRelease = amountTotal;
            vestingSchedule.active = false;
        }
        amountToRelease = amountToRelease - vestingSchedule.released;
        vestingSchedule.released += amountToRelease;
    }

    // releases tokens from all vesting of the msg.sender
    function claim() public {
        address claimer = msg.sender;
        uint256 amountToRelease = 0;
        for (uint256 i = 0; i < vestings[claimer].length; i++) {
            if (vestings[claimer][i].active)
                amountToRelease += _claim(vestings[claimer][i]);
        }
        IERC20(tokenAddress).transfer(claimer, amountToRelease);
    }
}
