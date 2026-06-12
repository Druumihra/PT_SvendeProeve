/*
  Warnings:

  - Made the column `usersId` on table `Friends` required. This step will fail if there are existing NULL values in that column.

*/
-- DropForeignKey
ALTER TABLE `Friends` DROP FOREIGN KEY `Friends_usersId_fkey`;

-- DropIndex
DROP INDEX `Friends_usersId_fkey` ON `Friends`;

-- AlterTable
ALTER TABLE `Friends` MODIFY `usersId` INTEGER NOT NULL;

-- AddForeignKey
ALTER TABLE `Friends` ADD CONSTRAINT `Friends_usersId_fkey` FOREIGN KEY (`usersId`) REFERENCES `Users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
