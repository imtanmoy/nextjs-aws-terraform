# Fetch AZs in the current region
data "aws_availability_zones" "azs" {
}


resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.name}-vpc-${var.env}"
    Environment = var.env
  }
}


#### Public subnets - internet facing  (lb, gateways)
resource "aws_subnet" "public_subnets" {
  count             = min(data.aws_availability_zones.azs.count, length(var.subnet_public_cidrblock))
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_public_cidrblock[count.index]
  availability_zone = data.aws_availability_zones.azs.names[count.index]
  tags              = {
    Name        = "${var.name}-public-subnet-${var.env}-${data.aws_availability_zones.azs.names[count.index]}"
    Environment = var.env
  }
}

#### Private subnets - Internal facing (apps, db etc)
resource "aws_subnet" "private_subnets" {
  count             = min(data.aws_availability_zones.azs.count, length(var.subnet_private_cidrblock))
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_private_cidrblock[count.index]
  availability_zone = data.aws_availability_zones.azs.names[count.index]

  tags = {
    Name        = "${var.name}-private-subnet-${var.env}-${data.aws_availability_zones.azs[count.index]}"
    Environment = var.env
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.name}-igw-${var.env}"
    Environment = var.env
  }
}

resource "aws_nat_gateway" "ngw" {
  count         = length(var.subnet_private_cidrblock)
  allocation_id = element(aws_eip.nat_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnets.*.id, count.index)
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name        = "${var.name}-nat-${var.env}-${format("%03d", count.index+1)}"
    Environment = var.env
  }
}

resource "aws_eip" "nat_eip" {
  count = length(var.subnet_private_cidrblock)
  vpc   = true

  tags = {
    Name        = "${var.name}-eip-${var.env}-${format("%03d", count.index+1)}"
    Environment = var.env
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.name}-routing-table-public"
    Environment = var.env
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table" "private" {
  count  = length(var.subnet_private_cidrblock)
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.name}-routing-table-private-${format("%03d", count.index+1)}"
    Environment = var.env
  }
}

resource "aws_route" "private" {
  count                  = length(compact(var.subnet_private_cidrblock))
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.ngw.*.id, count.index)
}

resource "aws_route_table_association" "private" {
  count          = length(var.subnet_private_cidrblock)
  subnet_id      = element(aws_subnet.private_subnets.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_route_table_association" "public" {
  count          = length(var.subnet_public_cidrblock)
  subnet_id      = element(aws_subnet.public_subnets.*.id, count.index)
  route_table_id = aws_route_table.public.id
}