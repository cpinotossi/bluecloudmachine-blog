targetScope='resourceGroup'

var parameters = json(loadTextContent('parameters.json'))

resource acr 'Microsoft.ContainerRegistry/registries@2019-05-01' = {
  name: parameters.prefix
  location: parameters.location
  sku: {
    name: 'Standard'
  }
}
