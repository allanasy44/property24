import { ReactNode } from "react";
import { StyleSheet, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useTheme } from "../constants/theme";

type ScreenProps = {
  children: ReactNode;
};

export function Screen({ children }: ScreenProps) {
  const { colors } = useTheme();

  return (
    <SafeAreaView style={[styles.safeArea, { backgroundColor: colors.background }]}>
      <View style={[styles.background, { backgroundColor: colors.background, borderColor: colors.border }]}>{children}</View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    alignItems: "center",
  },
  background: {
    flex: 1,
    width: "100%",
  },
});
