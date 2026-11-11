// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PassMembre} from "../src/PassMembre.sol";

contract PassMembreTest is Test {
    PassMembre pass;
    address admin = makeAddr("admin");
    address checker = makeAddr("checker");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    uint64 eventId;

    function setUp() public {
        pass = new PassMembre("PassMembre", "PASS", "https://passmembre.example/meta/", admin);
        vm.startPrank(admin);
        pass.grantRole(pass.CHECKER_ROLE(), checker);
        eventId = pass.createEvent("Soiree UQAR", uint64(block.timestamp + 7 days), 2);
        vm.stopPrank();
    }

    function _issue(address to, bool soulbound, uint64 validUntil) internal returns (uint256) {
        vm.prank(admin);
        return pass.issue(to, eventId, validUntil, soulbound);
    }

    function test_IssueAndMetadata() public {
        uint256 id = _issue(alice, false, 0);
        assertEq(pass.ownerOf(id), alice);
        assertTrue(pass.isValid(id));
        assertEq(pass.tokenURI(id), "https://passmembre.example/meta/1.json");
        assertEq(pass.getEvent(eventId).issued, 1);
    }

    function test_RevertWhen_SoldOut() public {
        _issue(alice, false, 0);
        _issue(bob, false, 0);
        vm.prank(admin);
        vm.expectRevert(PassMembre.SoldOut.selector);
        pass.issue(alice, eventId, 0, false);
    }

    function test_TransferableTicketCanBeResold() public {
        uint256 id = _issue(alice, false, 0);
        vm.prank(alice);
        pass.transferFrom(alice, bob, id);
        assertEq(pass.ownerOf(id), bob);
    }

    function test_SoulboundPassCannotBeTransferred() public {
        uint256 id = _issue(alice, true, 0);
        vm.prank(alice);
        vm.expectRevert(PassMembre.NonTransferable.selector);
        pass.transferFrom(alice, bob, id);
    }

    function test_CheckInOnlyOnce() public {
        uint256 id = _issue(alice, true, 0);
        vm.prank(checker);
        pass.checkIn(id);
        assertFalse(pass.isValid(id));
        vm.prank(checker);
        vm.expectRevert(PassMembre.AlreadyUsed.selector);
        pass.checkIn(id);
    }

    function test_ExpiredMembershipIsInvalid() public {
        uint256 id = _issue(alice, true, uint64(block.timestamp + 30 days));
        assertTrue(pass.isValid(id));
        vm.warp(block.timestamp + 31 days);
        assertFalse(pass.isValid(id));
        vm.prank(checker);
        vm.expectRevert(PassMembre.InvalidPass.selector);
        pass.checkIn(id);
    }

    function test_RevokeFreesTheSeat() public {
        uint256 id = _issue(alice, true, 0);
        _issue(bob, false, 0);
        vm.prank(admin);
        pass.revoke(id); // fonctionne même pour un pass non transférable
        assertFalse(pass.isValid(id));
        assertEq(pass.getEvent(eventId).issued, 1);
        _issue(alice, false, 0); // la place est de nouveau disponible
    }

    function test_RevertWhen_UnauthorizedRoles() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, pass.ISSUER_ROLE())
        );
        pass.issue(alice, eventId, 0, false);

        uint256 id = _issue(alice, false, 0);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, pass.CHECKER_ROLE())
        );
        pass.checkIn(id);
    }

    function test_RevertWhen_UnknownEventOrZeroCapacity() public {
        vm.startPrank(admin);
        vm.expectRevert(PassMembre.UnknownEvent.selector);
        pass.issue(alice, 999, 0, false);
        vm.expectRevert(PassMembre.InvalidCapacity.selector);
        pass.createEvent("Vide", 0, 0);
        vm.stopPrank();
    }

    function testFuzz_NeverExceedsCapacity(uint8 capacity, uint8 attempts) public {
        capacity = uint8(bound(capacity, 1, 50));
        attempts = uint8(bound(attempts, 0, 80));
        vm.startPrank(admin);
        uint64 e = pass.createEvent("Fuzz", 0, capacity);
        uint256 ok;
        for (uint256 i = 0; i < attempts; i++) {
            try pass.issue(address(uint160(1000 + i)), e, 0, false) {
                ok++;
            } catch {}
        }
        vm.stopPrank();
        assertLe(pass.getEvent(e).issued, capacity);
        assertEq(ok, attempts < capacity ? attempts : capacity);
    }
}
