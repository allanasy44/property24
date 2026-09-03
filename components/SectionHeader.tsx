import { StyleSheet, Text, View } from "react-native";
import { typography, useTheme } from "../constants/theme";

type SectionHeaderProps = {
  title: string;
  subtitle?: string;
};

export function SectionHeader({ title, subtitle }: SectionHeaderProps) {
  const { colors } = useTheme();
  const styles = StyleSheet.create({
    container: { gap: 4 },
    title: { color: colors.text, fontSize: 20, lineHeight: 25, ...typography.title },
    subtitle: { color: colors.textMuted, lineHeight: 20, fontSize: 13, ...typography.body },
  });

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{title}</Text>
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
    </View>
  );
}
