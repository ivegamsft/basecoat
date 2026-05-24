import { Entity, PrimaryColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';
import { Audit } from './audit.entity';

export enum Severity {
  CRITICAL = 'critical',
  HIGH = 'high',
  MEDIUM = 'medium',
  LOW = 'low',
  INFO = 'info',
}

export enum FindingStatus {
  OPEN = 'open',
  ACKNOWLEDGED = 'acknowledged',
  RESOLVED = 'resolved',
  FALSE_POSITIVE = 'false_positive',
}

@Entity('findings')
export class Finding {
  @PrimaryColumn('uuid')
  id: string = uuidv4();

  @Column('uuid')
  auditId: string;

  @ManyToOne(() => Audit, (audit) => audit.findings, { onDelete: 'CASCADE' })
  audit: Audit;

  @Column({
    type: 'enum',
    enum: Severity,
  })
  severity: Severity;

  @Column('varchar')
  category: string;

  @Column('text')
  description: string;

  @Column('text', { nullable: true })
  remediation: string;

  @Column({
    type: 'enum',
    enum: FindingStatus,
    default: FindingStatus.OPEN,
  })
  status: FindingStatus;

  @Column('varchar', { nullable: true })
  reference: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
