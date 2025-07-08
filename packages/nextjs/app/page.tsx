"use client";

import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { AuctionDashboard } from "~~/components/AuctionDashboard";
import { UserActions } from "~~/components/UserActions";

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();

  return (
    <div className="flex min-h-screen">
      {/* Main Auction Dashboard */}
      <div className="flex-1 p-6">
        <AuctionDashboard />
      </div>

      {/* User Actions Sidebar */}
      {connectedAddress && (
        <div className="w-80 glass-green border-l border-primary/20 p-6 min-h-screen">
          <div className="mb-8">
            <h2 className="text-xl font-bold text-base-content mb-3">My Account</h2>
            <div className="text-sm text-base-content/70 break-all font-mono glass p-3 rounded-lg">
              {connectedAddress}
            </div>
          </div>
          <UserActions />
        </div>
      )}
    </div>
  );
};

export default Home;
