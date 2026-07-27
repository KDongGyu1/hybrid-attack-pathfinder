import { ApiProperty } from '@nestjs/swagger';
import { Role } from '../../common/enums/role.enum';

export class UserResponseDto {
  @ApiProperty({ example: 'user-uuid-1234' })
  id: string;

  @ApiProperty({ example: 'analyst@company.com' })
  email: string;

  @ApiProperty({ enum: Role })
  role: Role;
}
