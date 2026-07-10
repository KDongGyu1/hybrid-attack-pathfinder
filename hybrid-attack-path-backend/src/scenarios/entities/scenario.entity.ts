import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity('scenarios')
export class Scenario {
  @PrimaryColumn()
  id: string;

  @Column()
  name: string;

  @Column({ type: 'text' })
  description: string;

  @Column({ type: 'enum', enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'] })
  severity: string;

  // Backend 1 그래프 데이터셋 식별자 (GET /graph/:graphId 조회용)
  @Column({ nullable: true })
  graphId?: string;

  @Column({ type: 'jsonb', nullable: true })
  mitreTactics?: string[];
}
