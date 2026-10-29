import mongoose from "mongoose";

export const connectToDatabase = async (uri: string): Promise<void> => {
  if (mongoose.connection.readyState === 1) {
    return;
  }

  await mongoose.connect(uri);
};

export const disconnectFromDatabase = async (): Promise<void> => {
  if (mongoose.connection.readyState === 0) {
    return;
  }

  await mongoose.disconnect();
};

export const databaseIsReady = (): boolean =>
  mongoose.connection.readyState === 1;
