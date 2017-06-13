az vm deallocate --resource-group Igloo-POC-rg --name centos6temp2
az vm generalize --resource-group Igloo-POC-rg --name centos6temp2
az image create --resource-group Igloo-POC-rg --name Centos6 --source centos6temp2