import { Entity, PrimaryColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';

@Entity('teams')
export class Team {
  @PrimaryColumn('uuid')
  id: string = uuidv4();

  @Column('varchar')
  name: string;

  @Column('text', { nullable: true })
  description: string;

  @Column('simple-array', { nullable: true })
  members: string[]; // Array of user IDs

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
