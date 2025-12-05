-- Add missing columns to users table
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "phoneHash" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "isVerified" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "isActive" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "referralCode" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "referredBy" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "referralRewardsCount" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "currentStreak" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "longestStreak" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "lastPostDate" TIMESTAMP(3);
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "streakFreezeCount" INTEGER NOT NULL DEFAULT 0;

-- Create unique index for referralCode (only if column exists)
CREATE UNIQUE INDEX IF NOT EXISTS "users_referralCode_key" ON "users"("referralCode");

-- CreateEnum for GatheringInviteStatus (if not exists)
DO $$ BEGIN
    CREATE TYPE "GatheringInviteStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- CreateEnum for ReferralStatus (if not exists)
DO $$ BEGIN
    CREATE TYPE "ReferralStatus" AS ENUM ('PENDING', 'USED', 'REWARDED', 'EXPIRED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add GATHERING_INVITE to NotificationType enum (if not exists)
DO $$ BEGIN
    ALTER TYPE "NotificationType" ADD VALUE 'GATHERING_INVITE';
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- CreateTable gathering_invites (if not exists)
CREATE TABLE IF NOT EXISTS "gathering_invites" (
    "id" TEXT NOT NULL,
    "gatheringId" TEXT NOT NULL,
    "inviterId" TEXT NOT NULL,
    "inviteeId" TEXT NOT NULL,
    "status" "GatheringInviteStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "respondedAt" TIMESTAMP(3),

    CONSTRAINT "gathering_invites_pkey" PRIMARY KEY ("id")
);

-- CreateTable referrals (if not exists)
CREATE TABLE IF NOT EXISTS "referrals" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "referrerId" TEXT NOT NULL,
    "refereeId" TEXT,
    "status" "ReferralStatus" NOT NULL DEFAULT 'PENDING',
    "rewardType" TEXT,
    "rewardAmount" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "referrals_pkey" PRIMARY KEY ("id")
);

-- CreateIndex for gathering_invites
CREATE UNIQUE INDEX IF NOT EXISTS "gathering_invites_gatheringId_inviteeId_key" ON "gathering_invites"("gatheringId", "inviteeId");
CREATE INDEX IF NOT EXISTS "gathering_invites_gatheringId_idx" ON "gathering_invites"("gatheringId");
CREATE INDEX IF NOT EXISTS "gathering_invites_inviterId_idx" ON "gathering_invites"("inviterId");
CREATE INDEX IF NOT EXISTS "gathering_invites_inviteeId_idx" ON "gathering_invites"("inviteeId");

-- CreateIndex for referrals
CREATE UNIQUE INDEX IF NOT EXISTS "referrals_code_key" ON "referrals"("code");
CREATE INDEX IF NOT EXISTS "referrals_referrerId_idx" ON "referrals"("referrerId");
CREATE INDEX IF NOT EXISTS "referrals_refereeId_idx" ON "referrals"("refereeId");
CREATE INDEX IF NOT EXISTS "referrals_code_idx" ON "referrals"("code");

-- AddForeignKey for gathering_invites
DO $$ BEGIN
    ALTER TABLE "gathering_invites" ADD CONSTRAINT "gathering_invites_inviterId_fkey" FOREIGN KEY ("inviterId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "gathering_invites" ADD CONSTRAINT "gathering_invites_inviteeId_fkey" FOREIGN KEY ("inviteeId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- AddForeignKey for referrals
DO $$ BEGIN
    ALTER TABLE "referrals" ADD CONSTRAINT "referrals_referrerId_fkey" FOREIGN KEY ("referrerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "referrals" ADD CONSTRAINT "referrals_refereeId_fkey" FOREIGN KEY ("refereeId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

