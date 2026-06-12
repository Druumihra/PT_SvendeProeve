/*
  Warnings:

  - You are about to drop the column `usersId` on the `Groups` table. All the data in the column will be lost.

*/
-- DropForeignKey
ALTER TABLE `Challenges` DROP FOREIGN KEY `Challenges_groupsId_fkey`;

-- DropForeignKey
ALTER TABLE `ChallengesResult` DROP FOREIGN KEY `ChallengesResult_challengesId_fkey`;

-- DropForeignKey
ALTER TABLE `ChallengesResult` DROP FOREIGN KEY `ChallengesResult_usersId_fkey`;

-- DropForeignKey
ALTER TABLE `Friends` DROP FOREIGN KEY `Friends_friendid_fkey`;

-- DropForeignKey
ALTER TABLE `Friends` DROP FOREIGN KEY `Friends_usersId_fkey`;

-- DropForeignKey
ALTER TABLE `GroupAdmins` DROP FOREIGN KEY `GroupAdmins_groupsId_fkey`;

-- DropForeignKey
ALTER TABLE `GroupAdmins` DROP FOREIGN KEY `GroupAdmins_usersId_fkey`;

-- DropForeignKey
ALTER TABLE `GroupMembers` DROP FOREIGN KEY `GroupMembers_groupsId_fkey`;

-- DropForeignKey
ALTER TABLE `GroupMembers` DROP FOREIGN KEY `GroupMembers_usersId_fkey`;

-- DropForeignKey
ALTER TABLE `votes` DROP FOREIGN KEY `votes_challengesId_fkey`;

-- DropIndex
DROP INDEX `Challenges_groupsId_fkey` ON `Challenges`;

-- DropIndex
DROP INDEX `ChallengesResult_challengesId_fkey` ON `ChallengesResult`;

-- DropIndex
DROP INDEX `Friends_friendid_fkey` ON `Friends`;

-- DropIndex
DROP INDEX `GroupAdmins_groupsId_fkey` ON `GroupAdmins`;

-- DropIndex
DROP INDEX `GroupMembers_groupsId_fkey` ON `GroupMembers`;

-- DropIndex
DROP INDEX `votes_challengesId_fkey` ON `votes`;

-- AlterTable
ALTER TABLE `Groups` DROP COLUMN `usersId`;

-- AddForeignKey
ALTER TABLE `Friends` ADD CONSTRAINT `Friends_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Friends` ADD CONSTRAINT `Friends_friendid_fkey` FOREIGN KEY (`friendid`) REFERENCES `Users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `GroupMembers` ADD CONSTRAINT `GroupMembers_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `GroupMembers` ADD CONSTRAINT `GroupMembers_groupsId_fkey` FOREIGN KEY (`groupsId`) REFERENCES `Groups`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `GroupAdmins` ADD CONSTRAINT `GroupAdmins_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `GroupAdmins` ADD CONSTRAINT `GroupAdmins_groupsId_fkey` FOREIGN KEY (`groupsId`) REFERENCES `Groups`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Challenges` ADD CONSTRAINT `Challenges_groupsId_fkey` FOREIGN KEY (`groupsId`) REFERENCES `Groups`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `votes` ADD CONSTRAINT `votes_challengesId_fkey` FOREIGN KEY (`challengesId`) REFERENCES `Challenges`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ChallengesResult` ADD CONSTRAINT `ChallengesResult_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ChallengesResult` ADD CONSTRAINT `ChallengesResult_challengesId_fkey` FOREIGN KEY (`challengesId`) REFERENCES `Challenges`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
