import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { GraphModule } from './graph/graph.module';
import { AssetsModule } from './assets/assets.module';
import { ScenariosModule } from './scenarios/scenarios.module';
import { LogsModule } from './logs/logs.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres' as const,
        host: config.get<string>('DB_HOST'),
        port: config.get<number>('DB_PORT'),
        username: config.get<string>('DB_USERNAME'),
        password: config.get<string>('DB_PASSWORD'),
        database: config.get<string>('DB_DATABASE'),
        autoLoadEntities: true,
        // 개발/발표 데모용 임시 설정. 운영에서는 반드시 false + 마이그레이션으로 전환.
        synchronize: true,
      }),
    }),
    AuthModule,
    GraphModule,
    AssetsModule,
    ScenariosModule,
    LogsModule,
  ],
})
export class AppModule {}
