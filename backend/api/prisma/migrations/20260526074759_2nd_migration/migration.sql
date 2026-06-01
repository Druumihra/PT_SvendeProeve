/*
  Warnings:

  - Added the required column `active` to the `Challenges` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updatedAt` to the `Challenges` table without a default value. This is not possible if the table is not empty.
  - Added the required column `admins` to the `Groups` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE `Challenges` ADD COLUMN `active` BOOLEAN NOT NULL,
    ADD COLUMN `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    ADD COLUMN `groupsId` INTEGER NULL,
    ADD COLUMN `updatedAt` DATETIME(3) NOT NULL,
    MODIFY `id` INTEGER NOT NULL AUTO_INCREMENT,
    ADD PRIMARY KEY (`id`);

-- AlterTable
ALTER TABLE `Groups` ADD COLUMN `admins` INTEGER NOT NULL,
    MODIFY `id` INTEGER NOT NULL AUTO_INCREMENT,
    ADD PRIMARY KEY (`id`);

-- AlterTable
ALTER TABLE `Users` ADD PRIMARY KEY (`id`);

-- CreateTable
CREATE TABLE `ChallengesResult` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `Result` VARCHAR(191) NOT NULL,
    `usersId` INTEGER NOT NULL,
    `challengesId` INTEGER NOT NULL,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `Challenges` ADD CONSTRAINT `Challenges_groupsId_fkey` FOREIGN KEY (`groupsId`) REFERENCES `Groups`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ChallengesResult` ADD CONSTRAINT `ChallengesResult_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ChallengesResult` ADD CONSTRAINT `ChallengesResult_challengesId_fkey` FOREIGN KEY (`challengesId`) REFERENCES `Challenges`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
