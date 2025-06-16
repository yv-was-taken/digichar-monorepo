"use client";

import { useEffect, useState } from "react";
import { Card, CardContent } from "~~/components/ui/card";
import { Progress } from "~~/components/ui/progress";

interface AuctionTimerProps {
  endTime: bigint;
  auctionDuration: bigint;
  className?: string;
}

export const AuctionTimer: React.FC<AuctionTimerProps> = ({ endTime, auctionDuration, className }) => {
  const [timeLeft, setTimeLeft] = useState<{
    days: number;
    hours: number;
    minutes: number;
    seconds: number;
    total: number;
    progressPercentage: number;
  }>({ days: 0, hours: 0, minutes: 0, seconds: 0, total: 0, progressPercentage: 0 });

  useEffect(() => {
    const updateTimer = () => {
      const now = Math.floor(Date.now() / 1000);
      const end = Number(endTime);
      const difference = end - now;

      if (difference > 0) {
        const days = Math.floor(difference / (24 * 60 * 60));
        const hours = Math.floor((difference % (24 * 60 * 60)) / (60 * 60));
        const minutes = Math.floor((difference % (60 * 60)) / 60);
        const seconds = Math.floor(difference % 60);

        // Calculate progress percentage
        const duration = Number(auctionDuration);
        const timeElapsed = duration - difference;
        const progressPercentage = Math.max(0, Math.min((1 - timeElapsed / duration) * 100, 100));

        setTimeLeft({ days, hours, minutes, seconds, total: difference, progressPercentage });
      } else {
        setTimeLeft({ days: 0, hours: 0, minutes: 0, seconds: 0, total: 0, progressPercentage: 100 });
      }
    };

    updateTimer();
    const interval = setInterval(updateTimer, 1000);

    return () => clearInterval(interval);
  }, [endTime, auctionDuration]);

  const formatTime = (time: number): string => {
    return time.toString().padStart(2, "0");
  };

  const isExpired = timeLeft.total <= 0;

  return (
    <Card className={`border-red-600 ${className}`}>
      <CardContent className="p-6">
        <div className="text-center space-y-4">
          {isExpired ? (
            <div className="text-2xl font-bold text-red-500">AUCTION ENDED</div>
          ) : (
            <>
              <div className="text-sm text-gray-400 uppercase tracking-wide">Auction Ends In</div>
              <div className="flex justify-center space-x-4 text-white">
                <div className="text-center">
                  <div className="text-2xl font-bold text-red-500">{formatTime(timeLeft.days)}</div>
                  <div className="text-xs text-gray-400">DAYS</div>
                </div>
                <div className="text-2xl font-bold text-gray-500">:</div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-red-500">{formatTime(timeLeft.hours)}</div>
                  <div className="text-xs text-gray-400">HOURS</div>
                </div>
                <div className="text-2xl font-bold text-gray-500">:</div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-red-500">{formatTime(timeLeft.minutes)}</div>
                  <div className="text-xs text-gray-400">MINUTES</div>
                </div>
                <div className="text-2xl font-bold text-gray-500">:</div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-red-500">{formatTime(timeLeft.seconds)}</div>
                  <div className="text-xs text-gray-400">SECONDS</div>
                </div>
              </div>
              <Progress value={timeLeft.progressPercentage} className="w-full" />
            </>
          )}
        </div>
      </CardContent>
    </Card>
  );
};
