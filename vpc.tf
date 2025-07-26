// ------------------ 1. Create a VPC ------------------
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.0.0.0/16"              // Primary CIDR block for the VPC, allows 65,536 IPs
  enable_dns_support   = true                       // Enables internal DNS resolution within the VPC
  enable_dns_hostnames = true                       // Assigns DNS hostnames to instances for easy access
  tags = {
    Name = "aws-prod"                                 // Tags the VPC resource for identification in the console
  }
}

// ------------------ 2. Declare Availability Zones to use ------------------
variable "vpc_availability_zones" {
  type        = list(string)                        // Data type is a list of strings
  description = "Availability Zones"                // Description of what the variable represents
  default     = ["us-west-1b", "us-west-1c"]      // Two AZs in the region for high availability
}

// ------------------ 3. Create Public Subnets ------------------
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.custom_vpc.id         // Associate subnet with previously created VPC
  count             = length(var.vpc_availability_zones) // Create one subnet per AZ using count
  cidr_block        = cidrsubnet(aws_vpc.custom_vpc.cidr_block, 8, count.index + 1)
  // cidrsubnet() carves out a smaller subnet from the VPC CIDR
  // - "10.0.0.0/16" is the base
  // - 8 means we're increasing subnet mask by 8 bits → /24
  // - count.index + 1 creates unique subnets like 10.0.1.0/24, 10.0.2.0/24, etc.

  availability_zone = element(var.vpc_availability_zones, count.index) // Distribute subnets across selected AZs
  tags = {
    Name = "AWS-Prod Public subnet ${count.index + 1}"    // Tag each subnet with a unique index
  }
}

// ------------------ 4. Create Private Subnets ------------------
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.custom_vpc.id
  count             = length(var.vpc_availability_zones) // One per AZ
  cidr_block        = cidrsubnet(aws_vpc.custom_vpc.cidr_block, 8, count.index + 3)
  // Similar to public subnets but starts from 10.0.3.0/24 and continues (to avoid overlap)

  availability_zone = element(var.vpc_availability_zones, count.index)
  tags = {
    Name = "AWS-Prod Private subnet ${count.index + 1}"
  }
}

// ------------------ 5. Create Internet Gateway ------------------
resource "aws_internet_gateway" "igw_vpc" {
  vpc_id = aws_vpc.custom_vpc.id                    // Attach to the VPC for outbound internet access
  tags = {
    Name = "AWS-Prod-Internet Gateway"                    // Tag it for clarity
  }
}

// ------------------ 6. Create Route Table for Public Subnets ------------------
resource "aws_route_table" "aws_prod_route_table_public_subnet" {
  vpc_id = aws_vpc.custom_vpc.id                    // Associate route table with VPC
  route {
    cidr_block = "0.0.0.0/0"                         // Route all outbound internet traffic
    gateway_id = aws_internet_gateway.igw_vpc.id    // Through the Internet Gateway
  }
  tags = {
    Name = "Public subnet Route Table"              // Tag the route table
  }
}

// ------------------ 7. Associate Route Table with Public Subnets ------------------
resource "aws_route_table_association" "public_subnet_association" {
  route_table_id = aws_route_table.aws_prod_route_table_public_subnet.id // Connect to public route table
  count          = length(var.vpc_availability_zones)              // One per AZ
  subnet_id      = element(aws_subnet.public_subnet[*].id, count.index)
  // Loop through each public subnet and associate it with the route table
}

// ------------------ 8. Allocate Elastic IP for NAT Gateway ------------------
resource "aws_eip" "eip" {
  domain     = "vpc"                               // VPC-specific EIP allocation (not EC2-Classic)
  depends_on = [aws_internet_gateway.igw_vpc]      // Ensure IGW is created before requesting EIP
}

// ------------------ 9. Create NAT Gateway ------------------
resource "aws_nat_gateway" "aws-prod-nat-gateway" {
  subnet_id     = element(aws_subnet.private_subnet[*].id, 0)
  // Place NAT Gateway in the first private subnet -- typically best practice is to put it in a public subnet, but your doc sets it here
  allocation_id = aws_eip.eip.id                   // Use the allocated Elastic IP
  depends_on    = [aws_internet_gateway.igw_vpc]   // Ensure IGW is provisioned first
  tags = {
    Name = "AWS-Prod-Nat Gateway"
  }
}

// ------------------ 10. Create Route Table for Private Subnets ------------------
resource "aws_route_table" "aws_prod_route_table_private_subnet" {
  vpc_id = aws_vpc.custom_vpc.id
  route {
    cidr_block = "0.0.0.0/0"                         // Allow outbound traffic
    gateway_id = aws_nat_gateway.aws-prod-nat-gateway.id  // Route through NAT Gateway instead of IGW
  }
  depends_on = [aws_nat_gateway.aws-prod-nat-gateway]     // Wait for NAT creation before this
  tags = {
    Name = "Private subnet Route Table"
  }
}

// ------------------ 11. Associate Route Table with Private Subnets ------------------
resource "aws_route_table_association" "private_subnet_association" {
  route_table_id = aws_route_table.aws_prod_route_table_private_subnet.id
  count          = length(var.vpc_availability_zones)     // One association per subnet
  subnet_id      = element(aws_subnet.private_subnet[*].id, count.index)
  // Attach route table to each private subnet to enable outbound access via NAT
}