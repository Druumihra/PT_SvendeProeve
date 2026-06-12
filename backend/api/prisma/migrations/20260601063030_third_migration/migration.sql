/*
  Warnings:

  - You are about to drop the column `admins` on the `Groups` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE `Groups` DROP COLUMN `admins`;

-- AlterTable
ALTER TABLE `Users` ADD COLUMN `profilepicture` VARCHAR(191) NOT NULL DEFAULT 'https://www.pngall.com/wp-content/uploads/5/Profile-PNG-High-Quality-Image.png';

-- CreateTable
CREATE TABLE `GroupAdmins` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `usersId` INTEGER NOT NULL,
    `groupsId` INTEGER NOT NULL,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `votes` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `usersId` INTEGER NULL,
    `challengesId` INTEGER NOT NULL,
    `vote` BOOLEAN NULL,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `GroupAdmins` ADD CONSTRAINT `GroupAdmins_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `GroupAdmins` ADD CONSTRAINT `GroupAdmins_groupsId_fkey` FOREIGN KEY (`groupsId`) REFERENCES `Groups`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `votes` ADD CONSTRAINT `votes_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `votes` ADD CONSTRAINT `votes_challengesId_fkey` FOREIGN KEY (`challengesId`) REFERENCES `Challenges`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
