// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;
 
import {Test} from "forge-std/Test.sol";
import {Crowdfund} from "../src/Crowdfund_v1.sol";
 
contract MaliciousOwner {
    address payable c;
    function setCrowdfund(address payable _c) external { c = _c; }
    receive() external payable {
        P p = new P();
        (bool ok, ) = address(p).call{value: 1 wei}("");
        require(ok);
        p.selfdestruct(c);
    }
}
 
contract P {
    receive() external payable {}
    function selfdestruct(address payable target) external {
        selfdestruct(target);
    }
}
 
contract CrowdfundTest is Test {
 
    Crowdfund public c;
    uint end_donate;
    uint goal;
 
    function setUp() public {
        
        // Deploy Crowdfund with a future deadline and a goal
        MaliciousOwner _MaliciousOwner = new MaliciousOwner();
        address payable owner = payable(address(_MaliciousOwner));
        end_donate = block.number + 10;
        goal = 1 ether;
        c = new Crowdfund(owner, end_donate, goal);
        _MaliciousOwner.setCrowdfund(payable(address(c)));
    }
 
    // wd-full-balance:
    // after a non-reverting `withdraw`, the whole balance of the contract is sent to `owner`.
 
    // PoC produced by GPT-5:
    // - Deploy Crowdfund with owner set to a malicious Owner contract and goal G > 0;
    //  ensure end_donate has not passed yet.
    // - A backer donates >= G before end_donate.
    // - After block.number > end_donate, call Crowdfund.withdraw().
    // - Owner’s fallback/receive, triggered by the transfer, calls a helper contract P
    //  that selfdestructs to Crowdfund (P.selfdestruct(payable(Crowdfund))) sending,
    //  say, 1 wei to Crowdfund during the external call.
    // - Owner’s fallback returns successfully; withdraw does not revert.
    // - After withdraw returns, Crowdfund now holds 1 wei (from selfdestruct)
    //  that was not sent to owner, violating the property.
 
 
    function test_wd_full_balance() public {
        address backer = address(123);
 
        // Before end_donate: backer donates >= G
        vm.roll(end_donate - 1);
 
        vm.deal(backer, 2 ether);
        vm.prank(backer);
        c.donate{value: 2 ether}();
  
        // After end_donate: (backer) calls withdraw()
        vm.roll(end_donate + 1);
 
        vm.prank(backer);
        (bool success,) = address(c).call{value: 0}(abi.encodeWithSignature("withdraw()"));
        assert(success);                     // Ensuring withdraw() does not revert
 
        uint Crowdfund_balance_after = address(c).balance;     // Balance of Crowdfund after withdraw()
 
        // after a non-reverting `withdraw`,
        // the whole balance of the contract is NOT sent to `owner`.
        assert(Crowdfund_balance_after != 0);
    }
 
}