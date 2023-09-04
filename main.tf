provider "aws" {
  region = "eu-central-1" # Replace with your desired region
}
resource "aws_vpc" "my_vpc" {
  cidr_block = "192.168.0.0/24" # Adjust the VPC CIDR block as needed
}

resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = element(["192.168.0.0/26", "192.168.0.64/26"], count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = element(["192.168.0.128/26", "192.168.0.192/26"], count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}
data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_nat_gateway" "my_nat_gateway" {
  count             = 2
  allocation_id     = aws_eip.my_eip[count.index].id
  subnet_id         = element(aws_subnet.public_subnet[*].id, count.index)
}

resource "aws_eip" "my_eip" {
  count = 2
}

resource "aws_instance" "bastion" {
  ami           = "ami-0766f68f0b06ab145" # Replace with a valid AMI ID
  instance_type = "t2.micro"              # Adjust as needed
  subnet_id     = element(aws_subnet.public_subnet[*].id, 0)
  key_name      = "dev_ops_itca"    # Replace with your key pair
  tags = {
    Name = "Bastion"
  }
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
}

resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-"
  description = "Bastion Security Group"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust for more specific access
  }
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_instance" "cicd_instance" {
  ami           = "ami-0766f68f0b06ab145" # Replace with a valid AMI ID
  instance_type = "t2.micro"              # Adjust as needed
  subnet_id     = element(aws_subnet.private_subnet[*].id, 0)
  tags = {
    Name = "CI/CD Instance"
  }
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = aws_subnet.private_subnet[*].id
}

resource "aws_db_instance" "my_db_instance" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql" # Replace with your desired RDS engine
  engine_version       = "5.7"   # Replace with your desired version
  instance_class       = "db.t2.micro"
  identifier           = "mydb"  # Specify your desired RDS instance name here
  username             = "admin"
  password             = "qwerty123$"
  multi_az             = false
  publicly_accessible  = false
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name
}

resource "aws_security_group" "db_sg" {
  name_prefix = "db-"
  description = "RDS Security Group"
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # Assuming Bastion instance
  }
  vpc_id = aws_vpc.my_vpc.id
}
