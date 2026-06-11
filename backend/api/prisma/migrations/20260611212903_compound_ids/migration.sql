/*
  Warnings:

  - The primary key for the `ChallengesResult` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to drop the column `Result` on the `ChallengesResult` table. All the data in the column will be lost.
  - You are about to drop the column `id` on the `ChallengesResult` table. All the data in the column will be lost.
  - The primary key for the `Friends` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to drop the column `id` on the `Friends` table. All the data in the column will be lost.
  - The primary key for the `GroupAdmins` table will be changed. If it partially fails, the table could be left without primary key constraint.
  - You are about to drop the column `id` on the `GroupAdmins` table. All the data in the column will be lost.
  - Added the required column `score` to the `Challenges` table without a default value. This is not possible if the table is not empty.
  - Made the column `groupsId` on table `Challenges` required. This step will fail if there are existing NULL values in that column.
  - Added the required column `proof` to the `ChallengesResult` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE `Challenges` DROP FOREIGN KEY `Challenges_groupsId_fkey`;

-- DropForeignKey
ALTER TABLE `Groups` DROP FOREIGN KEY `Groups_usersId_fkey`;

-- DropIndex
DROP INDEX `Challenges_groupsId_fkey` ON `Challenges`;

-- DropIndex
DROP INDEX `Groups_usersId_fkey` ON `Groups`;

-- AlterTable
ALTER TABLE `Challenges` ADD COLUMN `score` INTEGER NOT NULL,
    MODIFY `groupsId` INTEGER NOT NULL;

-- AlterTable
ALTER TABLE `ChallengesResult` DROP PRIMARY KEY,
    DROP COLUMN `Result`,
    DROP COLUMN `id`,
    ADD COLUMN `date` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ADD COLUMN `proof` LONGBLOB NOT NULL,
    ADD COLUMN `validated` BOOLEAN NOT NULL DEFAULT false,
    ADD PRIMARY KEY (`usersId`, `challengesId`);

-- AlterTable
ALTER TABLE `Friends` DROP PRIMARY KEY,
    DROP COLUMN `id`,
    ADD PRIMARY KEY (`usersId`);

-- AlterTable
ALTER TABLE `GroupAdmins` DROP PRIMARY KEY,
    DROP COLUMN `id`,
    ADD PRIMARY KEY (`usersId`, `groupsId`);

-- AlterTable
ALTER TABLE `Users` MODIFY `profilepicture` LONGBLOB NULL;

-- CreateTable
CREATE TABLE `GroupMembers` (
    `usersId` INTEGER NOT NULL,
    `groupsId` INTEGER NOT NULL,

    PRIMARY KEY (`usersId`, `groupsId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `GroupMembers` ADD CONSTRAINT `GroupMembers_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `GroupMembers` ADD CONSTRAINT `GroupMembers_groupsId_fkey` FOREIGN KEY (`groupsId`) REFERENCES `Groups`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Challenges` ADD CONSTRAINT `Challenges_groupsId_fkey` FOREIGN KEY (`groupsId`) REFERENCES `Groups`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
