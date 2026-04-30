from freqtrade.strategy import IStrategy
import talib.abstract as ta
import pandas as pd

class MyFirstStrategy(IStrategy):

    stoploss = -0.05
    minimal_roi = {
        "0":  0.03,
        "30": 0.02,
        "60": 0.01
    }
    trailing_stop = True
    timeframe = '15m'

    def populate_indicators(self, df, metadata):
        df['rsi'] = ta.RSI(df['close'], timeperiod=14)
        macd = ta.MACD(df['close'])
        df['macd']   = macd['macd']
        df['signal'] = macd['macdsignal']
        bb = ta.BBANDS(df['close'], timeperiod=20)
        df['bb_upper'] = bb['upperband']
        df['bb_lower'] = bb['lowerband']
        return df

    def populate_entry_trend(self, df, metadata):
        df.loc[
            (df['rsi'] < 35) &
            (df['macd'] > df['signal']) &
            (df['close'] < df['bb_lower']),
            'enter_long'] = 1
        return df

    def populate_exit_trend(self, df, metadata):
        df.loc[
            (df['rsi'] > 65) &
            (df['macd'] < df['signal']),
            'exit_long'] = 1
        return df
