import { Entity, PrimaryColumn, Column, CreateDateColumn, UpdateDateColumn, OneToMany } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';
import { Audit } from './audit.entity';

export enum UserRole {
  ADMIN = 'admin',
  AUDITOR = 'auditor',
  DEVELOPER = 'developer',
  VIEWER = 'viewer',
}

@Entity('users')
export class User {
  @PrimaryColumn('uuid')
  id: string = uuidv4();

  @Column('varchar', { unique: true })
  email: string;

  @Column('varchar')
  name: string;

  @Column('varchar')
  passwordHash: string;

  @Column({
    type: 'enum',
    enum: UserRole,
    default: UserRole.VIEWER,
  })
  role: UserRole;

  @Column('varchar', { nullable: true })
  avatarUrl: string;

  @Column('boolean', { default: false })
  emailVerified: boolean;

  @Column('varchar', { nullable: true })
  githubId: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @Column('timestamp', { nullable: true })
  lastLoginAt: Date;

  @OneToMany(() => Audit, (audit) => audit.createdBy)
  audits: Audit[];
}
