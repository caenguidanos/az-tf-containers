## Initialize Terraform

```powershell
terraform init -upgrade
```

## Create Terraform Execution Plan

```powershell
terraform plan -out main.tfplan
```

## Apply Terraform Execution Plan

```powershell
terraform apply main.tfplan
```

## Clean up

```powershell
terraform plan -destroy -out main.destroy.tfplan
```

```powershell
terraform apply main.destroy.tfplan
```
