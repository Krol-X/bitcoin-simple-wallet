# frozen_string_literal: true

require_relative '../../dto'

module Wallet
  module Api
    module Providers

      module Mempool
        module Mappers
          module_function

          def address(json)
            Dto::Account.new(
              address: json.fetch('address'),
              chain_stats: stats(json.fetch('chain_stats')),
              mempool_stats: stats(json.fetch('mempool_stats'))
            )
          end

          def utxo(json)
            Dto::Utxo.new(
              txid: json.fetch('txid'),
              vout: json.fetch('vout'),
              value: json.fetch('value'),
              confirmed: status(json)['confirmed'] == true,
              block_height: status(json)['block_height']
            )
          end

          def transaction(json)
            Dto::Transactions.new(
              txid: json.fetch('txid'),
              version: json['version'],
              locktime: json['locktime'],
              size: json['size'],
              weight: json['weight'],
              fee: json['fee'],
              confirmed: status(json)['confirmed'] == true,
              block_height: status(json)['block_height'],
              block_time: status(json)['block_time']
            )
          end

          def stats(json)
            Dto::Stats.new(
              tx_count: json.fetch('tx_count'),
              funded_txo_count: json.fetch('funded_txo_count'),
              funded_txo_sum: json.fetch('funded_txo_sum'),
              spent_txo_count: json.fetch('spent_txo_count'),
              spent_txo_sum: json.fetch('spent_txo_sum')
            )
          end

          def status(json)
            json['status'] || {}
          end
        end
      end
    end
  end
end