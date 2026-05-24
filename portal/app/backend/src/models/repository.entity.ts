import { Entity, PrimaryColumn, Column, CreateDateColumn, UpdateDateColumn, ManyToOne, OneToMany } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';
import { Team } from './team.entity';
import { Audit } from './audit.entity';

export enum ComplianceLevel {
  LEVEL1 = 'level1',
  LEVEL2 = 'level2',
  LEVEL3 = 'level3',
  LEVEL4 = 'level4',
}

@Entity('repositories')
export class Repository {
  @PrimaryColumn('uuid')
  id: string = uuidv4();

  @Column('varchar')
  name: string;

  @Column('varchar')
  url: string;

  @Column('uuid')
  teamId: string;

  @ManyToOne(() => Team)
  team: Team;

  @Column('boolean', { default: false })
  isPrivate: boolean;

  @Column('varchar', { nullable: true })
  language: string;

  @Column({
    type: 'enum',
    enum: ComplianceLevel,
    default: ComplianceLevel.LEVEL1,
  })
  complianceLevel: ComplianceLevel;

  @Column('timestamp', { nullable: true })
  lastAuditAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @OneToMany(() => Audit, (audit) => audit.repository)
  audits: Audit[];
}
