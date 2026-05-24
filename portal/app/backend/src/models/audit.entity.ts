import { Entity, PrimaryColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne, OneToMany } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';
import { Repository } from './repository.entity';
import { User } from './user.entity';
import { Finding } from './finding.entity';

export enum AuditType {
  SECURITY = 'security',
  COMPLIANCE = 'compliance',
  CODE_QUALITY = 'code-quality',
  DEPENDENCY = 'dependency',
}

export enum AuditStatus {
  PENDING = 'pending',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  FAILED = 'failed',
}

@Entity('audits')
export class Audit {
  @PrimaryColumn('uuid')
  id: string = uuidv4();

  @Column('uuid')
  repositoryId: string;

  @ManyToOne(() => Repository, (repo) => repo.audits)
  repository: Repository;

  @Column('uuid')
  createdById: string;

  @ManyToOne(() => User, (user) => user.audits)
  createdBy: User;

  @Column({
    type: 'enum',
    enum: AuditType,
  })
  type: AuditType;

  @Column({
    type: 'enum',
    enum: AuditStatus,
    default: AuditStatus.PENDING,
  })
  status: AuditStatus;

  @Column('jsonb', { nullable: true })
  metadata: Record<string, unknown>;

  @Column('text', { nullable: true })
  summary: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @Column('timestamp', { nullable: true })
  completedAt: Date;

  @OneToMany(() => Finding, (finding) => finding.audit, { cascade: true })
  findings: Finding[];
}
