"use client";

import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { AuctionDashboard } from "~~/components/AuctionDashboard";
import { UserActions } from "~~/components/UserActions";

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();

  return (
    <div className="flex">
      {/* Main Auction Dashboard */}
      <div className="flex-1">
        <AuctionDashboard />
      </div>

      {/* User Actions Sidebar */}
      {connectedAddress && (
        <div className="w-80 bg-gray-900 border-l border-gray-700 p-6 min-h-screen">
          <div className="mb-6">
            <h2 className="text-xl font-bold text-white mb-2">My Account</h2>
            <div className="text-sm text-gray-400 break-all">{connectedAddress}</div>
          </div>
          <UserActions />
        </div>
      )}
    </div>
  );
};

export default Home;
