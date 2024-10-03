-- CreateTable
CREATE TABLE "EducationLevel" (
    "id" SERIAL NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "EducationLevel_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "EducationLevel_code_key" ON "EducationLevel"("code");
