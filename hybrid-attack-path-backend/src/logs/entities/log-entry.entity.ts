import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';
import { AuditAction } from '../dto/log-query.dto';

@Entity('audit_logs')
export class LogEntry {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column()
  userEmail: string;

  @Column({ type: 'enum', enum: AuditAction })
  action: AuditAction;

  @Column()
  targetResource: string;

  @Column()
  ipAddress: string;

  @CreateDateColumn()
  createdAt: Date;
}
