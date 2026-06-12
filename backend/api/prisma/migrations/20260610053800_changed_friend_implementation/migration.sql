/*
  Warnings:

  - You are about to drop the `_FriendsToUsers` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `friendid` to the `Friends` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE `_FriendsToUsers` DROP FOREIGN KEY `_FriendsToUsers_A_fkey`;

-- DropForeignKey
ALTER TABLE `_FriendsToUsers` DROP FOREIGN KEY `_FriendsToUsers_B_fkey`;

-- AlterTable
ALTER TABLE `Friends` ADD COLUMN `friendid` INTEGER NOT NULL,
    ADD COLUMN `usersId` INTEGER NULL;

-- DropTable
DROP TABLE `_FriendsToUsers`;

-- AddForeignKey
ALTER TABLE `Friends` ADD CONSTRAINT `Friends_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Friends` ADD CONSTRAINT `Friends_friendid_fkey` FOREIGN KEY (`friendid`) REFERENCES `Users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
